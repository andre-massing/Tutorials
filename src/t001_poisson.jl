# # Tutorial 1: Poisson equation
#
#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/notebooks/t001_poisson.ipynb)
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/notebooks/t001_poisson.ipynb)
#
# ## Learning outcomes
#
# - How to solve a simple PDE in Julia with Gridap
# - How to load a discrete model (aka a FE mesh) from a file
# - How to build Conforming Lagrangian FE spaces
# - How to define the different terms in a weak form
# - How to impose Dirichlet and Neumann boundary conditions
# - How to visualize results
#
# ## Problem statement
#
# We want to solve the Poisson equation on the 3D domain depicted in the figure below with Dirichlet and Neumann boundary conditions. Dirichlet boundary conditions are applied on $\Gamma_{\rm D}$, being the outer sides of the prism (marked in red). Non-homogeneous Neumann conditions are applied to the internal boundaries $\Gamma_{\rm G}$, $\Gamma_{\rm Y}$, and $\Gamma_{\rm B}$ (marked in green, yellow and blue respectively). And homogeneous Neumann boundary conditions are applied in $\Gamma_{\rm W}$, the remaining portion of the boundary (marked in white).
#
# ![model](../models/model-r1.png)
#
# Formally, the problem to solve is: find $u$ such that
#
# ```math
# \left\lbrace
# \begin{aligned}
# -\Delta u = f  \ \text{in} \ \Omega\\
# u = g \ \text{on}\ \Gamma_{\rm D}\\
# \nabla u\cdot n = h \ \text{on}\  \Gamma_{\rm N}\\
# \end{aligned}
# \right.
# ```
#
# being $n$ the outwards unit normal vector to the Neumann boundary $\Gamma_{\rm N} \doteq \Gamma_{\rm G}\cup\Gamma_{\rm Y}\cup\Gamma_{\rm B}\cup\Gamma_{\rm W}$. For simplicity, we chose $f(x) = 1$, $g(x) = 2$, and $h(x)=3$ on $\Gamma_{\rm G}\cup\Gamma_{\rm Y}\cup\Gamma_{\rm B}$ and $h(x)=0$ on $\Gamma_{\rm W}$. The variable $x$ is the position vector $x=(x_1,x_2,x_3)$.
#
# ## Numerical scheme
#
# In this first tutorial, we use a conventional Galerkin finite element (FE) method with conforming Lagrangian finite element spaces. The model problem reduces to the weak equation: find $u\in U_g$ such that $ a(v,u) = b(v) $ for all $v\in V_0$, where $U_g$ and $V_0$ are the subset of functions in $H^1(\Omega)$ that fulfill the Dirichlet boundary condition $g$ and $0$ respectively. The bilinear and linear forms for this problems are
# ```math
# a(v,u) \doteq \int_{\Omega} \nabla v \cdot \nabla u \ {\rm d}\Omega, \quad b(v) \doteq \int_{\Omega} v\ f  \ {\rm  d}\Omega + \int_{\Gamma_{\rm N}} v\ g \ {\rm d}\Gamma_{\rm N}
# ```
#
# ## Implementation
#
# In order to solve this problem in Gridap,  we are going to build the main objects that are involved in the weak formulation.  The step number 0 is to load the Gridap project. If you have configured your environment properly, it is simply done like this:

using Gridap

# ### Discrete model

# As in any FE simulation, we need a discretization of the computational domain (i.e a FE mesh), which contains information of the different boundaries to impose boundary conditions. All geometrical data needed for solving a FE problem is provided in Gridap by types inheriting from the abstract type `DiscreteModel`. In the following line, we build an instance of `DiscreteModel` by loading a model from a `json` file.

model = DiscreteModelFromFile("../models/model.json");

# You can easily inspect the generated model in Paraview by writing it in `vtk` format.

writevtk(model,"model");

# The previous line generates four different files `model_0.vtu`, `model_1.vtu`, `model_2.vtu`, and `model_3.vtu` containing the vertices, edges, faces, and cells present in the discrete model. Moreover, you can easily inspect which boundaries are defined within the model.
#
# For instance, if we want to see which faces of the model are on the boundary $\Gamma_{\rm B}$ (i.e., the walls of the circular hole), open the file `model_2.vtu` and chose coloring by the element field "circle". You should see that only the faces on the circular hole have a value different from 0.
#
# ![](../assets/t001_poisson/fig_faces_on_circle.png)
#
# It is also possible to see which vertices are on the Dirichlet boundary $\Gamma_{\rm D}$. To do so, open the file `model_0.vtu` and chose coloring by the field "sides".
#
# ![](../assets/t001_poisson/fig_vertices_on_sides.png)
#
# That is, the boundary $\Gamma_{\rm B}$ (i.e., the walls of the circular hole) is called "circle" and the Dirichlet boundary $\Gamma_{\rm D}$ is called "sides" in the model. In addition, the walls of the triangular hole $\Gamma_{\rm G}$ and the walls of the square hole $\Gamma_{\rm Y}$ are identified in the model with the names "triangle" and "square" respectively.
#
#
# ### FE spaces
#
# Once we have a discretization of the computational domain, the next step is to generate a discrete approximation of the finite element spaces $V_0$ and $U_g$ (i.e. the test and trial FE spaces) of the problem. To do so, first, we are going to build a discretization of $H^1(\Omega)$, namely $V$, defined as the standard Conforming Lagrangian FE space (without boundary conditions) associated with the discretization of the computational domain. Note that functions in $V$ are free on the Dirichlet boundary (which is not the case for $V_0$ and $U_g$). The FE space $V$ is build as follows:

order = 1
diritag = "sides"
V = CLagrangianFESpace(Float64,model,order,diritag);

#
# In the first argument, we pass the data type that represents the value of the functions in the space. In that case, `Float64` since the unknown of our problem is scalar-valued and it will be represented with a 64-bit floating point number. In addition, we pass the model on top of which we want to construct the space, the interpolation order, and the name of the entities that are on the Dirichlet boundary. Note that, even though functions in $V$ are not constrained by Dirichlet boundary conditions, the underlaying implementation is aware of which functions have support on the Dirichlet boundary. This is why we need to pass the argument `diritag`.
#
#
# The approximations for the test and trial spaces $V_0$ and $U_g$ are build simply as

g(x) = 2.0
V0 = TestFESpace(V)
Ug = TrialFESpace(V,g);

# Note that functions in the test space are always constrained to 0 on the Dirichlet boundary, whereas functions on the trial space are constrained to the given boundary function. In this case, function $g$.
#
# ### Numerical integration
#
# Once we have build the interpolation spaces, the next step is to set up the machinery to perform the integrals in the weak form numerically. Here, we need to compute integrals on the interior of the domain $\Omega$ and on the Neumann boundary $\Gamma_{\rm N}$. In both cases, we need two main ingredients. We need to define an integration mesh (i.e. a set of cells that form a partition of the integration domain), plus a Gauss-like quadrature in each of the cells. In Gridap, integration meshes are represented by types inheriting from the abstract type `Triangulation`. For integrating on the domain $\Omega$, we build the following integration mesh and quadrature:

trian = Triangulation(model)
quad = CellQuadrature(trian,order=2);

# Note that in this simple case, we are using the cells of the model as integration cells, but in more complex formulations (e.g., embedded finite element computations) the integration cells can be different from the cells on the background FE mesh. Note also, that we are constructing a quadrature of order 2 in the cells of the integration mesh. This is enough for integrating all terms of the weak form exactly for an interpolation of order 1.

#
# On the other hand, we need a special type of integration mesh, represented by the type `BoundaryTriangulation`, to integrate on the boundary. We build an instance of this type from the discrete model and the names used to identify the Neumann boundary as follows:

neumanntags = ["circle", "triangle", "square"]
btrian = BoundaryTriangulation(model,neumanntags)
bquad = CellQuadrature(btrian,order=2);

#  Note that we have also created a quadrature of order 2 on top of the integration mesh for the Neumann boundary.
#
# ### Weak form
#
# With all the ingredients presented so far, we are ready to define our FE problem.  First, we need to define the weak form of the problem at hand. This is done by means of types inheriting from the abstract type `FETerm`. In this tutorial, we will use the sub-types `AffineFETerm` and `FESource`. An `AffineFETerm` is a term that contributes both to the system matrix and the right-hand-side vector, whereas a `FESource` only contributes to the right hand side vector.
#
# In this example, we use an `AffineFETerm` to represent all the terms in the weak form that are integrated over the interior of the domain $\Omega$. It is constructed like this:
#

f(x) = 1.0
a(v,u) = inner( ∇(v), ∇(u) )
b_Ω(v) = inner(v, f)
t_Ω = AffineFETerm(a,b_Ω,trian,quad);

#
# In the first argument, we pass a function that represents the integrand of the bilinear form $a(\cdot,\cdot)$, the second argument is a function that represents the integrand of part of the linear form $b(\cdot)$ that is integrated over the domain $\Omega$. The third argument is the `Triangulation` on which we want to perform the integration (in that case the integration mesh for $\Omega$), and the last argument is the `CellQuadrature` needed to perform the integration numerically.
#
# Note that the contribution associated with the Neumann condition is integrated over a different domain, and thus, cannot be included in the previous `AffineFETerm`. To account for it, we use a `FESource` object:

h(x) = 3.0
b_Γ(v) = inner(v, h)
t_Γ = FESource(b_Γ,btrian,bquad);

# Here, we pass in the first argument the integrand of the Neumann boundary condition, and in the last arguments we pass the integration mesh and quadrature for the Neumann boundary.
#
# Presenting the precise notation used to define the integrands of the weak form is out of the scope of this first tutorial. But for the moment, the following remarks are enough. Variables `v` and `u`  represents a test and trial function respectively. The function `∇` represents the gradient operator. The function `inner` represents the inner product. It is extremely important to be aware that the *implementation* of the `inner` function is not commutative! The first argument is always for the test function (which will be associated with the rows of the system matrix or the right hand side vector depending on the case). Not following this rule can end up with matrices that are the transpose of the matrix you really want or with code crashes in the worst case. Note that we have always correctly placed the test function `v` in the first argument.
#
# ### FE problem
#
# At this point, we can combine all ingredients and formulate our FE problem. A FE problem (both for linear and nonlinear cases) is represented in the code by types inheriting from the abstract type `FEOperator`. Since we want to solve a linear problem, we use the concrete type `LinearFEOperator`:

assem = SparseMatrixAssembler(V0,Ug)
op = LinearFEOperator(V0,Ug,assem,t_Ω,t_Γ);

# Note that we build the `LinearFEOperator` object from the test and trial FE spaces and the FE terms constructed before. We also need to provide an `Assembler` object, which represents the strategy to assemble the system. In this case, we use a `SparseMatrixAssembler`, which will use Julia build-in sparse matrices.
#
# ### Solver phase
#
# We have constructed a FE problem, the last step is to solve it. In Gridap, FE problems are solved with types inheriting from the abstract type `FESolver`. Since this is a linear problem, we use a `LinearFESolver`:

ls = LUSolver()
solver = LinearFESolver(ls)

# `LinearFESolver` objects are build from a given algebraic linear solver. In this case, we use a LU factorization. Now we are ready to solve the problem as follows:

uh = solve(solver,op);

# The solution of the problem `uh` is an instance of `FEFunction`, the type used to represent a function in a FE space. We can inspect the result by writing it into a vtk file:

writevtk(trian,"results",cellfields=["uh"=>uh]);

# which will generate a file named `results.vtu` having a nodal field named `uh` containing the solution of our problem. If you open it, you will see something like this:
#
# ![](../assets/t001_poisson/fig_uh.png)
#

#
# ## Summary
#
# Since this has been a quite long tutorial, we end up by wrapping all the code we have used.

using Gridap

#Read the discrete model
model = DiscreteModelFromFile("../models/model.json")

#Setup FE space
order = 1
diritag = "sides"
V = CLagrangianFESpace(Float64,model,order,diritag)

#Setup test and trial spaces
g(x) = 2.0
V0 = TestFESpace(V)
Ug = TrialFESpace(V,g)

#Setup numerical integration (volume)
trian = Triangulation(model)
quad = CellQuadrature(trian,order=2)

#Setup numerical integration (boundary)
neumanntags = ["circle", "triangle", "square"]
btrian = BoundaryTriangulation(model,neumanntags)
bquad = CellQuadrature(btrian,order=2)

#Setup FE terms (volume)
f(x) = 1.0
a(v,u) = inner( ∇(v), ∇(u) )
b_Ω(v) = inner(v, f)
t_Ω = AffineFETerm(a,b_Ω,trian,quad)

#Setup FE terms (boundary)
h(x) = 3.0
b_Γ(v) = inner(v, h)
t_Γ = FESource(b_Γ,btrian,bquad)

#Setup FE problem
assem = SparseMatrixAssembler(V0,Ug)
op = LinearFEOperator(V0,Ug,assem,t_Ω,t_Γ)

#Solve it!
ls = LUSolver()
solver = LinearFESolver(ls)
uh = solve(solver,op)

#Write results
writevtk(trian,"results",cellfields=["uh"=>uh])

#
#  Congrats, tutorial done!
#