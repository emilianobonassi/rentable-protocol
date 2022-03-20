require('dotenv').config()
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.13",
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${process.env.WEB3_INFURA_PROJECT_ID}`
      },
    initialBaseFeePerGas: 0
    }
  }
};
