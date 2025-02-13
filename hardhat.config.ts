import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import dotenv from 'dotenv';
dotenv.config();

const isDevelopment = process.env.NODE_ENV === 'development';

const config: HardhatUserConfig = {
  solidity: '0.8.28',
  networks: isDevelopment
    ? {}
    : {
        'base-mainnet': {
          url: `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
          accounts: [process.env.PRIVATE_KEY!],
        },
        'base-sepolia': {
          url: `https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
          accounts: [process.env.PRIVATE_KEY!],
        },
        'sepolia': {
          url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
          accounts: [process.env.PRIVATE_KEY!],
        },
      },
  etherscan: isDevelopment
    ? {}
    : {
        enabled: true,
        apiKey: {
          'base-mainnet': process.env.BASESCAN_API_KEY!,
          'base-sepolia': process.env.BASESCAN_API_KEY!,
          'sepolia': process.env.ETHERSCAN_API_KEY!,
        },
        customChains: [
          {
            chainId: 84532,
            urls: {
              apiURL: 'https://api-sepolia.basescan.org/api',
              browserURL: 'https://sepolia.basescan.org',
            },
            network: 'base-sepolia',
          },
          {
            chainId: 8453,
            urls: {
              apiURL: 'https://api.basescan.org/api',
              browserURL: 'https://basescan.org',
            },
            network: 'base-mainnet',
          },
        ],
      },
};

export default config;
