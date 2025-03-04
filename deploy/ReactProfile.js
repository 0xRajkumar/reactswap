module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer, dev } = await getNamedAccounts()

  const react = await ethers.getContract("ReactToken")

  let numberCakeToReactivate = ethers.utils.parseEther('1')
  let numberCakeToRegister = ethers.utils.parseEther('1')
  let numberCakeToUpdate = ethers.utils.parseEther('1')

  const { address } = await deploy("ReactProfile", {
    from: deployer,
    args: [react.address, numberCakeToReactivate, numberCakeToUpdate, numberCakeToRegister],
    log: true,
    deterministicDeployment: false
  })
}

module.exports.tags = ["ReactProfile"]
module.exports.dependencies = ["ReactToken"]
