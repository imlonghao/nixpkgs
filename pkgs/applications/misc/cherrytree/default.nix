{ lib, fetchFromGitHub, python2Packages, gettext }:

python2Packages.buildPythonApplication rec {
  pname = "cherrytree";
  version = "0.39.4";

  src = fetchFromGitHub {
    owner = "giuspen";
    repo = "cherrytree";
    rev = version;
    sha256 = "1wycgn1f3b858qb6kn2bsaabak8n52qkpd24w54xz6fjizlnw7x0";

  };

  nativeBuildInputs = [ gettext ];

  propagatedBuildInputs = with python2Packages; [ pygtk dbus-python pygtksourceview ];

  patches = [ ./subprocess.patch ];

  doCheck = false;

  meta = with lib; {
    description = "An hierarchical note taking application";
    longDescription = ''
      Cherrytree is an hierarchical note taking application, featuring rich
      text, syntax highlighting and powerful search capabilities. It organizes
      all information in units called "nodes", as in a tree, and can be very
      useful to store any piece of information, from tables and links to
      pictures and even entire documents. All those little bits of information
      you have scattered around your hard drive can be conveniently placed into
      a Cherrytree document where you can easily find it.
    '';
    homepage = "http://www.giuspen.com/cherrytree";
    license = licenses.gpl3;
    maintainers = with maintainers; [ ];
  };
}
