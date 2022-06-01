echo Line count:
find engine/ defend/ -name "*.d" -and -'!' -name "Bind.d" | xargs wc -l

echo File count:
find engine/ defend/ -name "*.d" -and -'!' -name "Bind.d" | wc -l
