//npx hardhat run scripts/upgradeFixedStaking.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);


const fixedStakingAddress = `0xFCe998CE29709dC5AC425506Ef310cA2a2004E07`


let fixedStaking;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address: ${ deployer.address}`);

    console.log(`Start upgrade Fixed staking contract`);
    const FixedStaking = await ethers.getContractFactory(`FixedStaking`);
    fixedStaking = await upgrades.upgradeProxy(fixedStakingAddress, FixedStaking);
    await fixedStaking.deployed();
    console.log(`Fixed staking contract upgraded`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
