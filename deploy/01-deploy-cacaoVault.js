const { network } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const delegatorLocal = (
        await ethers.getContract("DelegationRegistry", deployer)
    ).address
    const delegatorGoerli = "0x00000000000076A84feF008CDAbe6409d2FE638B"
    const delegator =
        chainId == 31337 || 1337 ? delegatorLocal : delegatorGoerli

    const name = "CacaoVaultToken"
    const symbol = "CVT"
    const args = [name, symbol, delegator]
    const cacaoVault = await deploy("CacaoVault", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (
        !(chainId === 31337 || chainId === 1337) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying")
        await verify(cacaoVault.address, args)
    }
    log("------------------------------------------------------")
}

module.exports.tags = ["cacaoVault", "all", "cacaos"]
