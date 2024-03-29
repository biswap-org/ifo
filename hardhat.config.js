require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
const { bscScanApiKey, privatKey } = require('./secrets.json');

task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      blockGasLimit: 5e6,
      gasPrice: 5e9,
      timeout: 1_000_000
    },
    hardhat: {
      blockGasLimit: 99999999,
      forking: {
        url: "https://restless-bitter-cherry.bsc.quiknode.pro/7cd27b905f7b140932a1f71bd22f24e575e0a3ca/"
      }
    },
    mainnetBSC: {
      url: "https://restless-bitter-cherry.bsc.quiknode.pro/7cd27b905f7b140932a1f71bd22f24e575e0a3ca/", //"https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 5e9,
      accounts: [privatKey]
    },
    testnetBSC: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 5e9,
      accounts: [privatKey]
    }
  },
  etherscan: {
    apiKey: bscScanApiKey
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          }
        }
      },
      {
        version: "0.8.2",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          }
        }
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          }
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999,
          }
        }
      }
    ],
    outputSelection: {
      "*": {
        "*": ["storageLayout"]
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 200000
  }
};
