const { network, getNamedAccounts } = require("hardhat")

async function main() {
    const { deployer } = await getNamedAccounts()
    const anotherWallet = "0x70666ADbCEF58bb8850b70C897892d14fAD477b9"
    const fbayc = await ethers.getContract("FakeBoredApeYachtClub", deployer)

    const mintAmount = 2
    for (let i = 0; i < mintAmount; i++) {
        await fbayc.safeMint(anotherWallet)
    }
    console.log("Minted " + mintAmount)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
