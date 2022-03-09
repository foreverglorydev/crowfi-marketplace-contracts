const { ethers } = require('hardhat');
const hre = require('hardhat')

async function main() {
    const [deployer] = await ethers.getSigners();
  
    console.log("Deploying contracts with the account:", deployer.address);
  
    console.log("Account balance:", (await deployer.getBalance()).toString());
  
    const CronosNFT = await ethers.getContractFactory("CronosNFT");
    const cronosNFT = await CronosNFT.deploy();
    await cronosNFT.deployed();
    console.log("NFT deployed address:", cronosNFT.address);

    const CronosMarket = await ethers.getContractFactory("CronosMarket");
    const cronosMarket = await CronosMarket.deploy();
    await cronosNFT.deployed();
    console.log("Market deployed address:", cronosMarket.address);

    const Auction = await ethers.getContractFactory("Auction");
    const auction = await Auction.deploy();
    await auction.deployed();
    console.log("Auction deployed address:", auction.address);

  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });