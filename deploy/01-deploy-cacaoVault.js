const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const delegatorLocal = (
        await ethers.getContract("DelegationRegistry", deployer)
    ).address
    const delegatorGoerli = "0x00000000000076A84feF008CDAbe6409d2FE638B"
    const delegator =
        network.config.chainId == 31337 || 1337
            ? delegatorLocal
            : delegatorGoerli

    const name = "CacaoVaultToken"
    const symbol = "CVT"
    const args = [name, symbol, delegator]
    const cacao = await deploy("CacaoVault", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("------------------------------------------------------")
}

module.exports.tags = ["cacaoVault", "all", "cacaos"]
