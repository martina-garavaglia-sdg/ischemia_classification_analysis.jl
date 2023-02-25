using DelimitedFiles
using Flux
using Flux: @epochs, onehotbatch, onecold, logitcrossentropy, train!, flatten
using Statistics: mean, std
using Flux.Data: DataLoader
using Plots
using ParametricMachinesDemos
using Optim, FluxOptTools

Random.seed!(3)
# Split train test data
train = readdlm("data/ECG200_TRAIN.txt")
test = readdlm("data/ECG200_TEST.txt")

y_train = train[:, 1]
y_test = test[:,1]
y_train = onehotbatch(y_train, (-1,1))
y_test = onehotbatch(y_test, (-1,1))

x_train = permutedims(train[:, 2:end], (2,1))
x_test = permutedims(test[:, 2:end], (2,1))

x_train = Flux.unsqueeze(x_train, 2)
x_test = Flux.unsqueeze(x_test, 2)


# Loading
train_data = DataLoader((x_train, y_train); batchsize = 32, shuffle = true);
test_data = DataLoader((x_test, y_test); batchsize = 32, shuffle = true);

# Model
dimensions = [1];

machine = RecurMachine(dimensions, sigmoid; pad=1, timeblock=5)

model = Flux.Chain(machine, flatten, Dense(96,2)) |> f64; #Dense(sum(dimensions),32), Dense(32,2))  #Conv((1,3), sum(dimensions) => 4),

opt = ADAM(0.01);

params = Flux.params(model);

# Loss function
loss(x,y) = logitcrossentropy(model(x), y)



# Training and plotting
epochs = Int64[]
loss_on_train = Float64[]
loss_on_test = Float64[]
acc_train = Float64[]
acc_test = Float64[]
best_params = Float32[]

for epoch in 1:500

    # Train
    Flux.train!(loss, params, train_data, opt)
    
    # Saving losses and accuracies for visualization
    push!(epochs, epoch)
    push!(loss_on_train, loss(x_train, y_train))
    push!(loss_on_test, loss(x_test, y_test))
    push!(acc_train, accuracy(y_train, model(x_train)))
    push!(acc_test, accuracy(y_test, model(x_test)))
    @show loss(x_train, y_train)
    @show loss(x_test, y_test)

    # Saving the best parameters
    if epoch > 1
        if is_best(loss_on_test[epoch-1], loss_on_test[epoch])
            best_params = params
        end
    end
end

@show maximum(acc_test)
@show minimum(loss_on_train)
@show minimum(loss_on_test)

# Extract and add new trained parameters
if isempty(best_params)
    best_params = params
end

Flux.loadparams!(model, best_params);


# Visualization
plot(epochs, loss_on_train, lab="Training loss", lw=2, ylims = (0,1));
plot!(epochs, loss_on_test, lab="Test loss", lw=2, ylims = (0,1));
#title!("Ischemie - rec machine");
yaxis!("Loss");
xaxis!("Training epochs");
savefig("visualization/losses/recurrent/ischemie_rec_loss.png");

plot(epochs, acc_train, lab="Training accuracy", lw=2, ylims = (0,1));
plot!(epochs, acc_test, lab="Test accuracy", lw=2, ylims = (0,1));
#title!("Ischemie - rec machine");
yaxis!("Accuracy");
xaxis!("Training epoch");
savefig("visualization/accuracies/recurrent/ischemie_rec_accuracy.png");


## LBFGS


Random.seed!(3)
dimensions = [32,32,32];
machine = DenseMachine(dimensions, sigmoid);

model_lbfgs = Flux.Chain(machine, Dense(sum(dimensions), 2)) |> f64;

model_lbfgs = cpu(model_lbfgs)

loss_lbfgs() = logitcrossentropy(model_lbfgs(x_train), y_train);

params_lbfgs = Flux.params(model_lbfgs);


lossfun, gradfun, fg!, p0 = optfuns(loss_lbfgs, params_lbfgs)
res = Optim.optimize(Optim.only_fg!(fg!), p0, Optim.Options(iterations=200, store_trace=true))

best_params_PM = res.minimizer
#copy flattened optimized params 
copy!(params_lbfgs, best_params_PM)

Flux.loadparams!(model_lbfgs, params_lbfgs)

accuracy(y_test, model_lbfgs(x_test))
logitcrossentropy(y_test, model_lbfgs(x_test))
logitcrossentropy(y_train, model_lbfgs(x_train))


