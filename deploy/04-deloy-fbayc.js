const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = []

    if (chainId === 31337 || chainId === 1337) {
        console.log("<< Local chain detected, deployed FBAYC locally >>")
        const fbayc = await deploy("FakeBoredApeYachtClub", {
            from: deployer,
            args: args,
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })
    } else {
        console.log(
            "<< deploying on chain = %d - using predeployed FBAYC contract >>",
            chainId
        )
    }
    log("------------------------------------------------------")
}

module.exports.tags = ["fbayc", "all"]
