
N = 1000

OS = "Manjaro"
CPU = "Ryzen 7 5800X"

vjulia = "1.8.0"
vgcc = "12.2.0"
vclang = "14.0.6"

set size ratio 0.5
set style data histogram
set style histogram cluster gap 1
set style fill solid border rgb "black"

set border 3 lw 1.3
set tics out nomirror

set grid y
set xrange [-0.75:4.75]
set ylabel "runtime in seconds"

set title sprintf("%s (%s, n = %d)", CPU, OS, N)

plot "times.dat" using 2:xtic(1) i 0 lc rgb "#3d5b99" title sprintf("julia %s", vjulia), \
     "" using 2:xtic(1) i 1 lc rgb "#3d7799" title sprintf("gcc %s", vgcc), \
     "" using 2:xtic(1) i 2 lc rgb "#3d9099" title sprintf("clang %s", vclang)
