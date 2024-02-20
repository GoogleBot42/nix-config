final: prev:

{
  libedgetpu = prev.callPackage ./libedgetpu { };
  actual-server = prev.callPackage ./actualbudget { };
}
