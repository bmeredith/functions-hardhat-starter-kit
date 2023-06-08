const { types } = require("hardhat/config")
const { networks } = require("../../networks")

task("functions-deploy-communityengine", "Deploys the CommunityEngine contract")
  .addOptionalParam("verify", "Set to true to verify client contract", true, types.boolean)
  .setAction(async (taskArgs) => {
    if (network.name === "hardhat") {
      throw Error(
        'This command cannot be used on a local hardhat chain.  Specify a valid network or simulate a CommunityEngine request locally with "npx hardhat functions-simulate".'
      )
    }

    console.log(`Deploying CommunityEngine contract to ${network.name}`)

    const oracleAddress = networks[network.name]["functionsOracleProxy"]

    console.log("\n__Compiling Contracts__")
    await run("compile")

    // Deploy CommunityEngine
    const clientContractFactory = await ethers.getContractFactory("CommunityEngine")
    const clientContract = await clientContractFactory.deploy(oracleAddress)

    console.log(
      `\nWaiting ${network.config.confirmations} blocks for transaction ${clientContract.deployTransaction.hash} to be confirmed...`
    )
    await clientContract.deployTransaction.wait(network.config.confirmations)

    // Verify the CommunityEngine Contract
    const verifyContract = taskArgs.verify

    if (verifyContract && (process.env.POLYGONSCAN_API_KEY || process.env.ETHERSCAN_API_KEY)) {
      try {
        console.log("\nVerifying contract...")
        await clientContract.deployTransaction.wait(Math.max(6 - network.config.confirmations, 0))
        await run("verify:verify", {
          address: clientContract.address,
          constructorArguments: [oracleAddress],
        })
        console.log("CommunityEngine verified")
      } catch (error) {
        if (!error.message.includes("Already Verified")) {
          console.log("Error verifying contract.  Try delete the ./build folder and try again.")
          console.log(error)
        } else {
          console.log("Contract already verified")
        }
      }
    } else if (verifyContract) {
      console.log("\nPOLYGONSCAN_API_KEY or ETHERSCAN_API_KEY missing. Skipping contract verification...")
    }

    console.log(`\nCommunityEngine contract deployed to ${clientContract.address} on ${network.name}`)
  })
