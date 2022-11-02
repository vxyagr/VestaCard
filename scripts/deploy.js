const { ethers, upgrades } = require("hardhat");

async function main() {
   let signer, vestaToken, vestaRandomizer, vestaCard;
  
    const gas = await ethers.provider.getGasPrice();
    const VestaToken = await ethers.getContractFactory("VestaToken");
    const VestaRandomizer = await ethers.getContractFactory("VestaRandomizer");
    const VestaCard = await ethers.getContractFactory("VestaCard");
    //to change how createCard accesses VRF Chainlink, between test and real deployment
    const test = false;
    
    [signer] = await ethers.provider.listAccounts();
    vestaToken = await VestaToken.deploy(signer,1000000000000);
    await vestaToken.deployed();

    vestaRandomizer = await VestaRandomizer.deploy();
    await vestaRandomizer.deployed();

    
    const tokenAddress = vestaToken.address;
    const randomizerAddress = vestaRandomizer.address;
    const signers=[signer];
    
    console.log("Deploying Initial Vesta Upgradeable contract...");
    vestaCard = await upgrades.deployProxy(VestaCard, [randomizerAddress,tokenAddress,signers,test], {
      gasPrice: gas, 
      initializer: "initialize",
   });
   await vestaCard.deployed();
   await vestaToken.setVestaCard(vestaCard.address);
   await vestaRandomizer.setVestaCard(vestaCard.address);

   console.log("VestaCard Contract deployed to:", vestaCard.address);
   console.log("VestaRandomizer Contract deployed to:", vestaRandomizer.address);
   console.log("VestaToken Contract deployed to:", vestaToken.address);
}

main().catch((error) => {
   console.error(error);
   process.exitCode = 1;
 });