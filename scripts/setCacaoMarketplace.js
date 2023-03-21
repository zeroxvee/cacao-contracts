const { network, getNamedAccounts, ethers } = require("hardhat")

async function setCacaoMarketplace() {
    const { deployer } = await getNamedAccounts()
    const CacaoVault = await ethers.getContract("CacaoVault", deployer)
    const Cacao = await ethers.getContract("Cacao", deployer)

    await CacaoVault.setMarketplaceAddress(Cacao.address)

    console.log("New Cacao Marketplace address set", Cacao.address)
}

module.exports = setCacaoMarketplace
