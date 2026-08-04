publish:
	pip install build 'twine>=1.5.0'
	python -m build
	twine upload dist/* --verbose
	rm -fr build dist

