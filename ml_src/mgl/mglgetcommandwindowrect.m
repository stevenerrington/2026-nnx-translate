function rect = mglgetcommandwindowrect()

desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
mainframe = desktop.getMainFrame;

if isempty(mainframe)
    rect = Pos2Rect(GetMonitorPosition(1));
else
    rect = [mainframe.getX mainframe.getY mainframe.getX+mainframe.getWidth mainframe.getY+mainframe.getHeight];
end
