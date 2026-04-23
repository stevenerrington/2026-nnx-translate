"""
bhv2_reader.py
--------------
Pure-Python / NumPy reader for MonkeyLogic BHV2 (*.bhv2) files.

BHV2 binary structure  (from NIMH ML official spec)
----------------------------------------------------
No global file header.  File is a sequence of variable blocks.
Each block:

  uint64   len(name)
  bytes    name  (UTF-8)
  uint64   8                    ← always 8 (size of the type field)
  uint64   type_id              ← see TYPE_MAP
  uint64   len(shape_bytes)     ← ndim * 8
  uint64[] shape                ← ndim values

For PRIMITIVE types (double, single, int*, uint*, logical, char):
  raw bytes follow in column-major order.
  char is UTF-16LE (2 bytes per character).

For STRUCT / OBJECT:
  uint64   n_fields
  then n_fields × n_elements child variable blocks
  (field 0 for all elements, then field 1 for all elements, etc.)
  Each child block has its own full 6-field header; the name in that
  header is the struct field name.

For CELL:
  n_elements child variable blocks in column-major order.
  Each child block has its own 6-field header (name is usually empty).

Reference: https://monkeylogic.nimh.nih.gov/docs_BHV2BinaryStructure.html
"""

import struct
import numpy as np
from pathlib import Path


# ---------------------------------------------------------------------------
# MATLAB type-ID table
# ---------------------------------------------------------------------------
TYPE_MAP = {
    0:  ("empty",   None,       0),
    1:  ("double",  np.float64, 8),
    2:  ("single",  np.float32, 4),
    3:  ("int8",    np.int8,    1),
    4:  ("int16",   np.int16,   2),
    5:  ("int32",   np.int32,   4),
    6:  ("int64",   np.int64,   8),
    7:  ("uint8",   np.uint8,   1),
    8:  ("uint16",  np.uint16,  2),
    9:  ("uint32",  np.uint32,  4),
    10: ("uint64",  np.uint64,  8),
    11: ("logical", np.uint8,   1),   # stored as uint8, cast to bool later
    12: ("char",    None,       2),   # UTF-16LE
    13: ("struct",  None,       None),
    14: ("cell",    None,       None),
    15: ("object",  None,       None),
    16: ("function_handle", None, None),
}


class BHV2Reader:

    def __init__(self, path):
        self._buf = Path(path).read_bytes()
        self._pos = 0

    # ------------------------------------------------------------------
    # Low-level helpers
    # ------------------------------------------------------------------

    def _remaining(self):
        return len(self._buf) - self._pos

    def _read(self, n):
        if n == 0:
            return b""
        end = self._pos + n
        if end > len(self._buf):
            raise EOFError(
                f"Need {n} bytes at offset {self._pos}, "
                f"only {len(self._buf) - self._pos} remain."
            )
        chunk = self._buf[self._pos:end]
        self._pos = end
        return chunk

    def _u64(self):
        return struct.unpack_from("<Q", self._read(8))[0]

    # ------------------------------------------------------------------
    # Header reader  →  (name, type_id, shape_tuple)
    # ------------------------------------------------------------------

    def _header(self):
        name_len = self._u64()
        name     = self._read(name_len).decode("utf-8", errors="replace")
        _        = self._u64()          # always 8
        type_id  = self._u64()
        sh_bytes = self._u64()
        ndim     = sh_bytes // 8
        shape    = tuple(self._u64() for _ in range(ndim))
        return name, type_id, shape

    # ------------------------------------------------------------------
    # Variable dispatcher
    # ------------------------------------------------------------------

    def _read_var(self):
        """Read one variable block; return (name, value)."""
        name, type_id, shape = self._header()
        kind, dtype, itemsize = TYPE_MAP.get(type_id, ("unknown", None, None))

        # ---- empty / zero-sized ----------------------------------------
        n_elements = int(np.prod(shape)) if shape else 0

        if kind == "empty" or n_elements == 0:
            return name, None

        # ---- numeric primitives ----------------------------------------
        if kind in ("double", "single",
                    "int8",  "int16",  "int32",  "int64",
                    "uint8", "uint16", "uint32", "uint64"):
            raw = self._read(n_elements * itemsize)
            arr = np.frombuffer(raw, dtype=np.dtype(dtype).newbyteorder("<"))
            arr = self._reshape(arr, shape)
            return name, self._squeeze(arr)

        # ---- logical ---------------------------------------------------
        if kind == "logical":
            raw = self._read(n_elements)
            arr = np.frombuffer(raw, dtype=np.uint8).astype(bool)
            arr = self._reshape(arr, shape)
            return name, self._squeeze(arr)

        # ---- char (UTF-16LE) -------------------------------------------
        if kind == "char":
            raw  = self._read(n_elements * 2)
            text = raw.decode("utf-16-le", errors="replace")
            if len(shape) == 2 and shape[0] > 1:
                rows, cols = shape[0], shape[1]
                return name, [text[r*cols:(r+1)*cols].rstrip("\x00")
                               for r in range(rows)]
            return name, text.rstrip("\x00")

        # ---- struct / object -------------------------------------------
        if kind in ("struct", "object"):
            return name, self._read_struct(shape)

        # ---- cell ------------------------------------------------------
        if kind == "cell":
            return name, self._read_cell(shape)

        # ---- unknown / function_handle ---------------------------------
        return name, None

    # ------------------------------------------------------------------
    # Struct body
    # ------------------------------------------------------------------

    def _read_struct(self, shape):
        """
        Layout after the 6-field header for a struct:

          uint64   n_fields
          for f in range(n_fields):
            for e in range(n_elements):
              full variable block  (6-field header + data)
              (the variable's *name* in that header == the field name)
        """
        n_fields   = self._u64()
        n_elements = int(np.prod(shape)) if shape else 1

        # Build n_elements dicts
        elements = [{} for _ in range(n_elements)]

        for _ in range(n_fields):
            for e in range(n_elements):
                fname, val = self._read_var()
                elements[e][fname] = val

        if n_elements == 1:
            return elements[0]

        arr = np.empty(n_elements, dtype=object)
        for i, d in enumerate(elements):
            arr[i] = d
        return arr.reshape(shape, order="F")

    # ------------------------------------------------------------------
    # Cell body
    # ------------------------------------------------------------------

    def _read_cell(self, shape):
        n_elements = int(np.prod(shape)) if shape else 0
        cells = []
        for _ in range(n_elements):
            _, val = self._read_var()
            cells.append(val)

        if not shape or shape == (1, n_elements) or shape == (n_elements,):
            return cells                        # return as flat list

        arr = np.empty(n_elements, dtype=object)
        for i, c in enumerate(cells):
            arr[i] = c
        return arr.reshape(shape, order="F")

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _reshape(arr, shape):
        if len(shape) > 1:
            return arr.reshape(shape, order="F")
        return arr.reshape(shape)

    @staticmethod
    def _squeeze(arr):
        if arr.size == 1:
            return arr.flat[0].item()
        return arr

    # ------------------------------------------------------------------
    # Public entry
    # ------------------------------------------------------------------

    def read_all(self):
        variables = {}
        while self._remaining() >= 8:          # need at least one u64
            try:
                name, value = self._read_var()
                if name:
                    variables[name] = value
            except EOFError:
                break
            except Exception as exc:
                print(f"[BHV2] Warning at offset {self._pos}: {exc}")
                break
        return variables


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def read_bhv2(filepath):
    """
    Read a MonkeyLogic BHV2 file.

    Returns
    -------
    dict
        Top-level MATLAB variables keyed by name.

        MATLAB type       Python/NumPy equivalent
        -------------     -----------------------
        double scalar     float
        double array      np.ndarray (float64, C order)
        char              str  (or list of str for 2-D char arrays)
        logical           bool / np.ndarray(bool)
        struct 1×1        dict
        struct array      np.ndarray of dicts (object dtype)
        cell 1-D          list
        cell N-D          np.ndarray of object
    """
    return BHV2Reader(filepath).read_all()


def bhv2_summary(data, indent=0):
    """Print a readable summary of the data dict returned by read_bhv2()."""
    pad = "  " * indent
    if not isinstance(data, dict):
        print(f"{pad}{repr(data)[:80]}")
        return

    if indent == 0:
        print("=" * 60)
        print("BHV2 file summary")
        print("=" * 60)

    for k, v in data.items():
        if isinstance(v, np.ndarray) and v.dtype == object:
            print(f"{pad}{k}: struct/cell array  shape={v.shape}")
            if v.size > 0 and isinstance(v.flat[0], dict):
                print(f"{pad}  (first element fields: "
                      f"{list(v.flat[0].keys())[:8]})")
        elif isinstance(v, np.ndarray):
            print(f"{pad}{k}: ndarray  shape={v.shape}  dtype={v.dtype}")
        elif isinstance(v, dict):
            n = len(v)
            print(f"{pad}{k}: struct ({n} fields)")
            if indent < 1:
                bhv2_summary(v, indent=indent + 1)
        elif isinstance(v, list):
            print(f"{pad}{k}: cell/list  len={len(v)}")
        elif v is None:
            print(f"{pad}{k}: <empty>")
        else:
            print(f"{pad}{k}: {type(v).__name__} = {repr(v)[:60]}")

    if indent == 0:
        print("=" * 60)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python bhv2_reader.py <file.bhv2>")
        sys.exit(1)
    d = read_bhv2(sys.argv[1])
    bhv2_summary(d)