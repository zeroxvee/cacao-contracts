const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    // const delegator = await ethers.getContractAt("DelegationRegistry", deployer); // localhost
    const delegator = "0x00000000000076A84feF008CDAbe6409d2FE638B";
    const fee = 3;

    const args = [delegator, fee]
    const cacao = await deploy("Cacao", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log("------------------------------------------------------")
}

module.exports.tags = ["cacao", "all"]