const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const name = "CacaoVaultToken"
    const symbol = "CVT"
    const args = [name, symbol]
    const cacao = await deploy("CacaoVault", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("------------------------------------------------------")
}

module.exports.tags = ["cacaoVault", "all", "cacaos"]
