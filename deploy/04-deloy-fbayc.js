const { network } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const args = []

    if (chainId === 31337 || chainId === 1337) {
        console.log("---  Local chain detected, deploying FBAYC locally  ---")
        const fbayc = await deploy("FakeBoredApeYachtClub", {
            from: deployer,
            args: args,
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })
        await verify(fbayc.address, args)
    } else {
        console.log(
            "---  deploying on chain = %d - using predeployed FBAYC contract = %s  ---",
            chainId,
            (await ethers.getContract("FakeBoredApeYachtClub", deployer))
                .address
        )
    }
    log("------------------------------------------------------")
}

module.exports.tags = ["fbayc", "all"]
