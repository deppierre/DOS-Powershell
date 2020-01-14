rem git init
rem git remote add origin git@github.com:user/repo
rem git add *
rem git commit -am 'message'
rem git push -f origin master

FOR %%A IN (Devops-Ansible Python) DO (
    cd %%A
    git config user.email pierre@depretz.eu
    git config user.name 'Pierre Depretz'
    git add .
    git commit -m %1
    git push
	cd ..
)