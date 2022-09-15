
set size ratio 0.75

set style data histogram
set style histogram cluster gap 1

set grid y

set style fill solid border rgb "black"

plot "times.dat" using 2:xtic(1) i 0 title "julia", \
     "" using 2:xtic(1) i 1 title "gcc", \
     "" using 2:xtic(1) i 2 title "clang"
