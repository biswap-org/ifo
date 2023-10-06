//npx hardhat run scripts/upgradeFixedStaking.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const ownerAddress = '0xBAfEFe87d57d4C5187eD9Bd5fab496B38aBDD5FF'
const divPoolAddress = `0x4C1AD5a67315D31F7A882c7d4b0E8d1A94C50255`
const INTEREST_PAYMENT_ROLE = '0x835db7a94fe9ccb9f50b4c2e65d61e6f73cafdbc1b827a4d8adfba1f67aad4f5'

const getImplementationAddress = async (
    proxyAddress,
    implSlotAddress = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
) => {
    const implHex = await ethers.provider.getStorageAt(proxyAddress,implSlotAddress)
    return ethers.utils.hexStripZeros(implHex)
}

async function impersonateAccount(acctAddress) {
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acctAddress],
    });
    return await ethers.getSigner(acctAddress);
}

async function main() {
    const deployer = network.name === `localhost` ? await impersonateAccount(ownerAddress) : (await ethers.getSigners())[0];
    console.log(`Deployer address: ${deployer.address}`);

    console.log(`Start upgrade Div pool contract old Impl address ${await getImplementationAddress(divPoolAddress)}`);
    const DivPool = await ethers.getContractFactory(`DivPool`, deployer);

    // await upgrades.forceImport(divPoolAddress, DivPool);
    const divPool = await upgrades.upgradeProxy(divPoolAddress, DivPool);
    await divPool.deployed();
    console.log(`Div pool contract upgraded new Impl address ${await getImplementationAddress(divPoolAddress)}`);
    console.log('set new Payment address')
    await divPool.grantRole(INTEREST_PAYMENT_ROLE, '0x321fB1002DD7fa1e8D2Ad5F697ADCdD6dFA6da13')

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
