const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = []
    if (chainId === 31337 || chainId === 1337) {
        console.log(
            "---  Local chain detected, deploying delegator locally  ---"
        )
        const delegator = await deploy("DelegationRegistry", {
            from: deployer,
            args: args,
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })
    } else {
        console.log(
            "---  deploying on chain = %d - using deployed delegator  ---",
            chainId
        )
    }
    log("------------------------------------------------------")
}

module.exports.tags = ["delegator", "all"]
