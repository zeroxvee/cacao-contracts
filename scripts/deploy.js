// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const mintFee = hre.ethers.utils.parseEther("0.01");
  const maxPerMint = 50;
  const URI = "https://us-central1-bayc-metadata.cloudfunctions.net/api/tokens/";

  const FBAYC = await hre.ethers.getContractFactory("FakeBoredApeYachtClub");
  const fbayc = await FBAYC.deploy();

  await fbayc.deployed();

  console.log(
    "Deployed"
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
