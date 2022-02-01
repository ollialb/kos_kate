@lazyGlobal OFF.

print "Unpacking KATE Bootloader.".
wait until ship:unpacked.
copyPath("0:kate/boot/kate_install_and_run.ks", "").
switch to 1.
print "Run KATE Bootloader.".
runOncePath("kate_install_and_run.ks").