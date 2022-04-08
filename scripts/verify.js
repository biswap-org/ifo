
const hre = require('hardhat');
const { ethers } = require(`hardhat`);
const {BigNumber} = require("ethers");

const ifoAddress = `0x6bB3822F5a62eF385A4653cEa6d9694D2F61Dd87`
const dealTokenAddress = '0x55d398326f99059ff775485246999027b3197955' //USDT
const offerTokenAddress = `0xbb2298061efAD9F304710094899E7D669bfae030`

const preMineSupply = expandTo18Decimals(1000000000);
const nameDealToken = `Test USDT`;
const nameOfferToken = `Test XPS`;
const symbolDealToken = `USDT`;
const symbolOfferToken = `XPS`;
const startBlock = 0;
const finishBlock = 0;


function expandTo18Decimals(n) {
    return (new BigNumber.from(n)).mul((new BigNumber.from(10)).pow(18))
}

async function main() {

    console.log(`Verify IFO contract`);
    res = await hre.run("verify:verify", {
        address: '0x7D5ACE42d80B58C4aF8C0108c9b8C82984883314',
        constructorArguments: [],
        optimizationFlag: true
    })
    console.log(res);

    // console.log(`Verify deal token contract`);
    // res = await hre.run("verify:verify", {
    //     address: dealTokenAddress,
    //     constructorArguments: [nameDealToken, symbolDealToken, preMineSupply]
    // })
    // console.log(res);

    // let res;
    // console.log(`Verify offer token contract`);
    // res = await hre.run("verify:verify", {
    //     address: offerTokenAddress,
    //     constructorArguments: [nameOfferToken, symbolOfferToken, preMineSupply]
    // })
    // console.log(res);
    //

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
