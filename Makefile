publish:
	pip install build 'twine>=1.5.0'
	python -m build
	twine upload dist/*
#	twine upload --repository testpypi dist/* --verbose
	rm -fr build dist

