# Mainline Community Engine - Reinventing KOL Collaborations

This use case showcases how Chainlink Functions can be used to facilitate a agreement between a project owner and a KOL, with Chainlink Functions being used to obtain the KOL's tweets.

The CommunityEngine contract represents an on-chain agreement and payment contract between a project owner and the KOL. Chainlink Functions is used to verify the KOL's tweets for the project based on the agreement signed, using Mainline's API. The KOL is paid in USDC. If the KOL fails to meet the agreement requirements, the USDC is then returned to the project owner.

The project owner and the KOL have an agreed payment amount. This payout is part of the smart contract's code and represents a trust-minimized, verifiable, on-chain record of the agreement. For example, the KOL will receive 100 USDC once they tweet using the agreed upon keywords. 

If the KOL tweets out using the agreed upon keywords, the Chainlink Functions code will also send out a status showing that the KOL sent out those tweets back to the smart contract so it can be recorded immutably on the blockchain. The returned value is passed through Chainlink's Off-Chain Reporting consensus mechanism - which the nodes in the Decentralized Oracle Network (DON). Once that status is recorded, the KOL is then paid out in USDC or the USDC is returned back to the project owner, and the project is completed.

# Overview

<p><b>This project is currently in a closed beta. Request access to send on-chain requests here <a href="https://functions.chain.link/">https://functions.chain.link/</a></b></p>

## Requirements

- Node.js version [18](https://nodejs.org/en/download/)

## Steps

1. Clone this repository to your local machine<br><br>
2. Open this directory in your command line, then run `npm install` to install all dependencies.<br><br>
3. Set the required environment variables.
   1. Set an encryption password for your environment variables to a secure password by running:<br>`npx env-enc set-pw`<br>
   2. Use the command `npx env-enc set` to set the required environment variables (see [Environment Variable Management](#environment-variable-management)):
      - _ETHEREUM_SEPOLIA_RPC_URL_ for the Sepolia network RPC
      - _PRIVATE_KEY_ for your development wallet
      - _ETHERSCAN_API_KEY_ for verifying the deployed contracts on [Etherscan](https://sepolia.etherscan.io)
      - _MAINLINE_API_KEY_ for retrieving a KOL's tweets from a Chainlink Function using [Mainline's API](https://getmainline.io)
4. There are two files to notice that the default example will use:
   - _contracts/app/CommunityEngine.sol_ contains the smart contract that will receive the data
   - _app.request.js_ contains JavaScript code that will be executed by each node of the DON<br><br>
5. Deploy and verify the client contract to an actual blockchain network by running:<br>`npx hardhat functions-deploy-communityengine --network ethereumSepolia --verify true`<br>**Note**: Make sure `ETHERSCAN_API_KEY` is set if using `--verify true`.<br><br>
6. Create, fund & authorize a new Functions billing subscription by running:<br> `npx hardhat functions-sub-create --network ethereumSepolia --amount <LINK-funding-amount> --contract <deployed-contract-address>`<br>**Note**: Ensure your wallet has a sufficient LINK balance before running this command. Testnet LINK can be obtained at <a href="https://faucets.chain.link/">faucets.chain.link</a>.<br><br>
7. Make an on-chain request by running:<br>`npx hardhat functions-request --network ethereumSepolia  --gaslimit 300000 --contract <deployed-contract-address> --subid <subscription-id>`

# Environment Variable Management

This repo uses the NPM package `@chainlink/env-enc` for keeping environment variables such as wallet private keys, RPC URLs, and other secrets encrypted at rest. This reduces the risk of credential exposure by ensuring credentials are not visible in plaintext.

By default, all encrypted environment variables will be stored in a file named `.env.enc` in the root directory of this repo.

First, set the encryption password by running the command `npx env-enc set-pw`.
The password must be set at the beginning of each new session.
If this password is lost, there will be no way to recover the encrypted environment variables.

Run the command `npx env-enc set` to set and save environment variables.
These variables will be loaded into your environment when the `config()` method is called at the top of `hardhat.config.js`.
Use `npx env-enc view` to view all currently saved environment variables.
When pressing _ENTER_, the terminal will be cleared to prevent these values from remaining visible.
Running `npx env-enc remove VAR_NAME_HERE` deletes the specified environment variable.
The command `npx env-enc remove-all` deletes the entire saved environment variable file.

When running this command on a Windows machine, you may receive a security confirmation prompt. Enter `r` to proceed.

> **NOTE:** When you finish each work session, close down your terminal to prevent your encryption password from becoming exposes if your machine is compromised.
