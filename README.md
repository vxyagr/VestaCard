# VestaCard
prepared for submission to Vestafinance<br/>

My answer, Modules, and explanation overview can be found  <a href="https://docs.google.com/spreadsheets/d/1bhITcm8-uRUj6bGg0D1VMKiH5pez_bCxqb2pEPx2qlU/edit#gid=1861049426">here : (please click to go to my google sheet) </a><br/>
This protocol consisted of 3 main part : ERC20 token, Randomizer, and the main protocol VestaCard contract

## Stack
hardhat + JS + chai + ethers
## Installation
1. copy the repository to a folder<br/>
2. with npm installed, run npm install and wait for all dependencies to be installed<br/>
3. change the API Key and Alchemy URL in ".env" file if necessary <br/>
4. run npx hardhat test to make sure things going well<br/>
5. run "npx hardhat run --network mumbai scripts/deploy.js" <br/>
6. and you may verify each contract if necessary (npx hardhat verify --contract "contracts/VestaCard.sol:VestaCard" <change with deployment address>  --network mumbai)
