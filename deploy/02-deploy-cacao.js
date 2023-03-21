const { network, ethers } = require("hardhat")
const { verify } = require("../utils/verify")
const setCacaoMarketplace = require("../scripts/setCacaoMarketplace")

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
    const fee = 3
    const cacaoVault = (await ethers.getContract("CacaoVault", deployer))
        .address

    const args = [delegator, cacaoVault, fee]
    const cacao = await deploy("Cacao", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("------------------------------------------------------")

    await setCacaoMarketplace()
    if (
        !(chainId === 31337 || chainId === 1337) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying")
        await verify(cacao.address, args)
    }
}

module.exports.tags = ["cacao", "all", "cacaos"]
