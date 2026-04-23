function menuFunction() {
	var x = document.getElementById("top-menu");
	x.style.height = ("14" === x.style.height.substring(0,2)) ? "2.8125em" : "14.375em";
}

function menuResizeFunction() {
	var x = document.getElementById("top-menu");
	x.style.height = "2.8125em";
}

function scrollToHash() {
	var x = window.location.hash;
	if (0 == x.length) return;
	var y = document.querySelector(x).offsetTop;
	var offset = document.getElementById("top-menu").offsetHeight + 20;
	window.scroll(0, y - offset);
}

function fixNavbarOnScroll() {
	var x = document.getElementById("top-menu");
	var y = document.getElementById("nav-bar");
	console.log(window.scrollY);
	if (45<window.scrollY) { y.style.top = 0; y.style.position = "fixed"; }
	if (window.scrollY<45) { y.style.top = x.style.bottom; y.style.position = "absolute"; }
}

function external_link() {
	return confirm('You are leaving the NIH website.\n\nThis external link provides additional information that is consistent with the intended purpose of this site. NIH cannot attest to the accuracy of a non-federal site.\n\nLinking to a non-federal site does not constitute an endorsement by NIH or any of its employees of the sponsors or the information and products presented on the site. You will be subject to the destination site’s privacy policy when you follow the link.');
}