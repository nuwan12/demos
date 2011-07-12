----------------------------------------------------------------------
-- A simple script that trains a conv net on the MNIST dataset,
-- using stochastic gradient descent.
--
-- This script demonstrates a classical example of training a simple
-- convolutional network on a 10-class classification problem. It
-- illustrates several points:
-- 1/ description of the network
-- 2/ choice of a cost function (criterion) to minimize
-- 3/ instantiation of a trainer, with definition of learning rate, 
--    decays, and momentums
-- 4/ creation of a dataset, from a simple directory of PNGs
-- 5/ running the trainer, which consists in showing all PNGs+Labels
--    to the network, and performing stochastic gradient descent 
--    updates
--
-- Clement Farabet  |  July  7, 2011, 12:44PM
----------------------------------------------------------------------

require 'xlua'
xrequire ('image', true)
xrequire ('nnx', true)

----------------------------------------------------------------------
-- parse options
--
op = xlua.OptionParser('%prog [options]')
op:option{'-s', '--save', action='store', dest='save', 
          default='scratch/mnist-net',
          help='file to save network after each epoch'}
op:option{'-l', '--load', action='store', dest='load',
          help='reload pretrained network'}
op:option{'-d', '--dataset', action='store', dest='dataset', 
          default='../datasets/mnist',
          help='path to MNIST root dir'}
op:option{'-w', '--www', action='store', dest='www', 
          default='http://data.neuflow.org/data/mnist.tgz',
          help='path to retrieve dataset online (if not available locally)'}
op:option{'-f', '--full', action='store_true', dest='full',
          help='use full dataset (60,000 samples) to train'}
op:option{'-v', '--visualize', action='store_true', dest='visualize',
          help='visualize the datasets'}
opt = op:parse()

torch.setdefaulttensortype('torch.DoubleTensor')

----------------------------------------------------------------------
-- define network to train: CSCSCF
--

nbClasses = 10
connex = {6,16,120}
fanin = {1,6,16}

convnet = nn.Sequential()
convnet:add(nn.SpatialConvolution(1,connex[1], 5, 5))
convnet:add(nn.Tanh())
convnet:add(nn.SpatialSubSampling(connex[1], 2, 2, 2, 2))
convnet:add(nn.Tanh())
convnet:add(nn.SpatialConvolution(connex[1],connex[2], 5, 5))
convnet:add(nn.Tanh())
convnet:add(nn.SpatialSubSampling(connex[2], 2, 2, 2, 2))
convnet:add(nn.Tanh())
convnet:add(nn.SpatialConvolution(connex[2],connex[3], 5, 5))
convnet:add(nn.Tanh())
convnet:add(nn.SpatialLinear(connex[3],nbClasses))

----------------------------------------------------------------------
-- training criterion: a simple Mean-Square Error
--
criterion = nn.MSECriterion()
criterion.sizeAverage = true

----------------------------------------------------------------------
-- trainer: std stochastic trainer, plus training hooks
--
trainer = nn.StochasticTrainer{module=convnet, 
                               criterion=criterion,
                               learningRate = 1e-2,
                               learningRateDecay = 0,
                               weightDecay = 1e-4,
                               maxEpoch = 50,
                               momentum = 0.5,
                               save = opt.save}
trainer:setShuffle(false)

classes = {'1','2','3','4','5','6','7','8','9','10'}

confusion = nn.ConfusionMatrix(nbClasses, classes)

trainer.hookTrainSample = function(trainer, sample)
   confusion:add(trainer.module.output, sample[2])
end

trainer.hookTestSample = function(trainer, sample)
   confusion:add(trainer.module.output, sample[2])
end

trainer.hookTrainEpoch = function(trainer)
   -- print confusion matrix
   print(confusion)
   confusion:zero()

   -- run on test_set
   trainer:test(testData)

   -- print confusion matrix
   print(confusion)
   confusion:zero()
end

----------------------------------------------------------------------
-- get/create dataset
--
path_dataset = opt.dataset
if not sys.dirp(path_dataset) then
   local path = sys.dirname(path_dataset)
   local tar = sys.basename(opt.www)
   os.execute('mkdir -p ' .. path .. '; '..
              'cd ' .. path .. '; '..
              'wget ' .. opt.www .. '; '..
              'tar xvf ' .. tar)
end

if opt.full then
   nbTrainingPatches = 60000
   nbTestingPatches = 10000 
else
   nbTrainingPatches = 2000
   nbTestingPatches = 1000
   print('<warning> only using 2000 samples to train quickly (use flag --full to use 60000 samples)')
end

trainData = nn.DataList()
for i,class in ipairs(classes) do
   local dir = sys.concat(path_dataset,'train',class)
   local subset = nn.DataSet{dataSetFolder = dir,
                             cacheFile = sys.concat(path_dataset,'train',class..'-cache'),
                             nbSamplesRequired = nbTrainingPatches/10, channels=1}
   subset:shuffle()
   trainData:appendDataSet(subset, class)
end

testData = nn.DataList()
for i,class in ipairs(classes) do
   local subset = nn.DataSet{dataSetFolder = sys.concat(path_dataset,'test',class),
                             cacheFile = sys.concat(path_dataset,'test',class..'-cache'),
                             nbSamplesRequired = nbTestingPatches/10, channels=1}
   subset:shuffle()
   testData:appendDataSet(subset, class)
end

if opt.visualize then
   trainData:display(100,'trainData')
   testData:display(100,'testData')
end

----------------------------------------------------------------------
-- and train !!
--
trainer:train(trainData)
