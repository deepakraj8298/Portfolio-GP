Visit - https://deepakraj8298.github.io/Portfolio-GP/


Build + Deployment steps
ng build --configuration production --base-href /Portfolio-GP/
cd dist/Portfolio
git init
git remote add origin https://<your_token>@github.com/deepakraj8298/Portfolio-GP.git
 git checkout -b gh-pages
git add .
git commit -m "Deploying Angular app to GitHub Pages"
git push -f origin gh-pages
