test:
	for x in t/*.t ; do echo $$x ; perl $$x ; done
