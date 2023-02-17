const { network, getNamedAccounts } = require("hardhat")

async function main() {
    const { deployer } = await getNamedAccounts()
    const anotherWallet = "0x459e213D8B5E79d706aB22b945e3aF983d51BC4C"
    const fbayc = await ethers.getContract("FakeBoredApeYachtClub", deployer)

    const mintAmount = 5
    for (let i = 0; i < mintAmount; i++) {
        await fbayc.safeMint(anotherWallet)
    }
    console.log("Minted " + mintAmount)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
