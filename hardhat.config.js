/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('dotenv').config()
 require("@nomiclabs/hardhat-waffle");

//  // Go to https://www.alchemyapi.io, sign up, create
//  // a new App in its dashboard, and replace "KEY" with its key
//  const ALCHEMY_API_KEY = "KEY";
 
//  // Replace this private key with your Ropsten account private key
//  // To export your private key from Metamask, open Metamask and
//  // go to Account Details > Export Private Key
//  // Be aware of NEVER putting real Ether into testing accounts
//  const ROPSTEN_PRIVATE_KEY = "YOUR ROPSTEN PRIVATE KEY";

 module.exports = {
  solidity: "0.8.4",
  // networks: {
  //   ropsten: {
  //     url: `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
  //     accounts: [`${ROPSTEN_PRIVATE_KEY}`]
  //   }
  // }
  
  networks: {
    hardhat: {
      chainID: 1337,
    },
    rinkeby: {
      chainId: 4,
      url: "https://rinkeby.infura.io/v3/453c03db4e284d4abbf11bf220b53bfe",
      timeout: 200000,
      gas: 2100000, 
      gasPrice: 8000000000
    }
  }
  
};
