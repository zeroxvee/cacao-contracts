const { network, ethers } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const delegatorLocal = (await ethers.getContract("DelegationRegistry", deployer)).address
    const delegatorGoerli = "0x00000000000076A84feF008CDAbe6409d2FE638B"
    const delegator = network.config.chainId == 31337 ? delegatorLocal : delegatorGoerli;
    const fee = 3;
    const cacaoVault = (await ethers.getContract("CacaoVault", deployer)).address

    const args = [delegator, cacaoVault, fee]
    const cacao = await deploy("Cacao", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("------------------------------------------------------")
}

module.exports.tags = ["cacao", "all"]