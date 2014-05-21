bzr log -n0 | grep 'committer:' | sed -e 's/^.*committer: //g' \
| sed -e 's/<.*>//g' | sed 's/[ \t]*$//' \
| sed -e 's/garth.*/Garth N. Wells/g' \
| sed -e 's/gnw20.*/Garth N. Wells/g' \
| sed -e 's/harish.*/Harish Narayanan/g' \
| sed -e 's/hnarayan.*/Harish Narayanan/g' \
| sed -e 's/ilmar.*/Ilmar Wilbers/g' \
| sed -e 's/Joachim B Haga/Joachim B. Haga/g' \
| sed -e 's/logg.*/Anders Logg/g' \
| sort | uniq -c | sort -k 2,2n -r | gawk '{print $2" "$3" "$4}'