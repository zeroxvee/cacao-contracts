const { network,getNamedAccounts } = require("hardhat")
const fs = require("fs")

async function main() {
    const {deployer} = await getNamedAccounts();
    console.log(deployer)
    const anotherWallet = "0x459e213D8B5E79d706aB22b945e3aF983d51BC4C";
//     const { deployments } = network
//     const {deploy} = deployments
//     const { deployer } = await getNamedAccounts()
// const abiFile = fs.readFileSync("artifacts/contracts/FakeBoredApedYachtClub.sol/FakeBoredApeYachtClub.json", "utf-8");
// console.log(abiFile);
  const fbayc = await ethers.getContract("FakeBoredApeYachtClub", deployer);
  const mintFee = hre.ethers.utils.parseEther("0.01");
  const maxPerMint = 50;
  const URI = "https://us-central1-bayc-metadata.cloudfunctions.net/api/tokens/";

//   const FBAYC = await hre.ethers.getContractFactory("FakeBoredApeYachtClub");
//   const fbayc = await FBAYC.deploy();
    const mintAmount = 5;
    for (let i = 0; i < mintAmount; i++) {
        await fbayc.safeMint(anotherWallet);
    }

  console.log(
    "Minted " + mintAmount
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
