function flush() { if (key != "" && ssd && hdd && !stripe) { print key, len, devs } key=""; ssd=0; hdd=0; stripe=0; devs="" }
/^u64s / { flush(); if ($4 == "extent") { key=$5; len=$7 } ; next }
key != "" && /^ *ptr:/ { split($3, a, ":"); d=a[1]; devs=devs d ","; if (d==0||d==1) ssd=1; else hdd=1; next }
key != "" && /^ *stripe_ptr:/ { stripe=1; next }
END { flush() }
