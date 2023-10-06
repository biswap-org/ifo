//npx hardhat run scripts/upgradeFixedStaking.js --network mainnetBSC
const { ethers, network, hardhat, upgrades} = require(`hardhat`);

const interests = require('./mrpUsers.json')

const ownerAddress = '0x321fB1002DD7fa1e8D2Ad5F697ADCdD6dFA6da13'
const divPoolAddress = `0x4C1AD5a67315D31F7A882c7d4b0E8d1A94C50255`

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

    const divPool = await ethers.getContractAt(`DivPool`, divPoolAddress, deployer);

    console.log('Total amount: ')
    console.log(interests.reduce((acc,num) => acc + +num.amount, 0))

    await divPool.interestPayment(interests.slice(0,1000));

    // console.log(interests)


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
