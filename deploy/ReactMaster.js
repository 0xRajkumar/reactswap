module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const react = await ethers.getContract("ReactToken")
  
  const { address } = await deploy("ReactMaster", {
    from: deployer,
    args: [react.address, dev, "1000000000000000000000", "0", "1000000000000000000000"],
    log: true,
    deterministicDeployment: false
  })

  if (await react.owner() !== address) {
    // Transfer React Ownership to Chef
    console.log("Transfer React Ownership to Chef")
    await (await react.transferOwnership(address)).wait()
  }

  const reactMaster = await ethers.getContract("ReactMaster")
  if (await reactMaster.owner() !== dev) {
    // Transfer ownership of ReactMaster to dev
    console.log("Transfer ownership of ReactMaster to dev")
    await (await reactMaster.transferOwnership(dev)).wait()
  }
}

module.exports.tags = ["ReactMaster"]
module.exports.dependencies = ["UniswapV2Factory", "UniswapV2Router02", "ReactToken"]
