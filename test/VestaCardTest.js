const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Vesta Card Testing", function () {
  let owner, vestaToken, vestaRandomizer, vestaCard, mainAccount, addr1, addr2;
  let addresses;
  
  before("deploy the contract instances", async function () {
    const gas = await ethers.provider.getGasPrice();
    const VestaToken = await ethers.getContractFactory("VestaToken");
    const VestaRandomizer = await ethers.getContractFactory("VestaRandomizer");
    const VestaCard = await ethers.getContractFactory("VestaCard");
    
    [owner,account1,account2] = await ethers.provider.listAccounts();
    vestaToken = await VestaToken.deploy(owner,1000000000000);
    await vestaToken.deployed();

    vestaRandomizer = await VestaRandomizer.deploy();
      await vestaRandomizer.deployed();
    // get default owner, in owner abstraction form
    
    const tokenAddress = vestaToken.address;
    const randomizerAddress = vestaRandomizer.address;
    const signers=[owner];
    //creating test for 3 users
    [mainAccount, addr1, addr2] = await ethers.getSigners();
    addresses = new Array(mainAccount, addr1, addr2);
    vestaCard = await upgrades.deployProxy(VestaCard, [randomizerAddress,tokenAddress,signers,true], {
      gasPrice: gas, 
      initializer: "initialize",
   });
   await vestaCard.deployed();
   await vestaToken.setVestaCard(vestaCard.address);
   await vestaRandomizer.setVestaCard(vestaCard.address);
   await vestaToken.transfer(addresses[1].address,10000000);
   await vestaToken.transfer(addresses[2].address,10000000);
   
    // get default owner, but just the address!
    
  });

  it("allows token minting", async function () {
    previousSupply = await vestaToken.totalSupply();
    newMintedSupply = 1000000000000;
    expectedNewSupply = newMintedSupply + parseInt(previousSupply);
    await vestaCard.mintVestaToken(newMintedSupply);
    newSupply = await vestaToken.totalSupply();
    assert.equal(parseInt(newSupply), parseInt(expectedNewSupply));
  });

  it("allows staking and check if token is safely transferred to VestaCard's wallet", async function () {
    amountToStake = 1000000;
    for(i=0;i<addresses.length;i++){
      vestaTokenBalance = parseInt(await vestaToken.balanceOf(vestaCard.address));
      await vestaToken.connect(addresses[i]).approve(vestaCard.address,amountToStake);
      await vestaCard.connect(addresses[i]).stake(amountToStake);
      newVestaTokenBalance = parseInt(await vestaToken.balanceOf(vestaCard.address));
      assert.equal(parseInt(await vestaCard.connect(addresses[i]).getStakedAmount()), amountToStake);
      assert.equal(newVestaTokenBalance, parseInt(vestaTokenBalance+amountToStake));
    }
  });



  it("allows unstaking by anyone to the original owner", async function () {
    for(i=0;i<addresses.length;i++){
      amountStaked = parseInt(await vestaCard.connect(addresses[i]).getStakedAmount());
      vestaBalanceBefore = parseInt(await vestaToken.balanceOf(addresses[i].address));
      await vestaCard.connect(addresses[i]).unstake(amountStaked, addresses[i].address);
      vestaBalanceAfter = parseInt(await vestaToken.balanceOf(addresses[i].address));
      balanceDifference=vestaBalanceAfter-vestaBalanceBefore;
      assert.equal(parseInt(await vestaCard.connect(addresses[i]).getStakedAmount()), 0);
      assert.equal(amountStaked, balanceDifference);
    }
  });
 
  it("allows multiple vesting", async function () {
    for(i=0;i<addresses.length;i++){
      await vestaToken.connect(addresses[i]).approve(vestaCard.address,600);
      await vestaCard.connect(addresses[i]).vestToken(100);
      await vestaCard.connect(addresses[i]).vestToken(200);
      await vestaCard.connect(addresses[i]).vestToken(300);
      vestings = await vestaCard.connect(addresses[i]).getVestings();
      assert.equal(vestings.length, 3);
    }
  });
/*
 
  it("should only allow release every after certain period", async function () {
    assert.equal(await faucet.owner(), ownerAddress);
  });
  */
  it("should allow panic vesting unlock by multisig, being set in the -BEFORE- hook", async function () {
     (await vestaCard.unlockAll());
    unlocked = await vestaCard.isUnlocked();
    assert.equal(unlocked, true);
  });

  //as long as there is enough token, allowance, and not being blacklisted, user can create cards
  it("allows card creation with properties generated from chainlink VRF", async function () {
    for(i=0;i<addresses.length;i++){
      await vestaToken.connect(addresses[i]).approve(vestaCard.address,200);
      await vestaCard.connect(addresses[i]).createCard(100,true);
      //console.log("card ID : " + JSON.stringify(cardId));
      cards = await vestaCard.connect(addresses[i]).getCardsOwnedAsObject(addresses[i].address);
      cardDetails=cards[cards.length-1];
      assert.notEqual(JSON.stringify(cardDetails.evolution,NaN));
      assert.notEqual(JSON.stringify(cardDetails.evolution,null));
      assert.notEqual(JSON.stringify(cardDetails.symbol,NaN));
      assert.notEqual(JSON.stringify(cardDetails.symbol,null));
    }

  });

  it("allows to sell card from any place as the function is set to public", async function () {
    for(i=0;i<addresses.length;i++){
      cards = await vestaCard.connect(addresses[i]).getCardsOwnedAsObject(addresses[i].address);
      cardDetails=cards[cards.length-1];
      await vestaCard.connect(addresses[i]).sellCard(parseInt(cardDetails[0]),1000);
      assert.equal(await vestaCard.connect(addresses[i]).isOnSale(cardDetails[0]),true);
    }
  });

  it("it should set the owner to be the deployer of the contract", async function () {
    assert.equal(await vestaCard.owner(), owner);
  });

/*
  


  it("should allow to buy card", async function () {
    assert.equal(await faucet.owner(), ownerAddress);
  });

  it("should allow to banish card and get token in return", async function () {
    assert.equal(await faucet.owner(), ownerAddress);
  });

  it("it should set the owner to be the deployer of the contract", async function () {
    assert.equal(await faucet.owner(), ownerAddress);
  });

  it("it should withdraw the correct amount", async function () {
    let withdrawAmount = ethers.utils.parseUnits("1", "ether");
    await expect(faucet.withdraw(withdrawAmount)).to.be.reverted;
  }); */
});