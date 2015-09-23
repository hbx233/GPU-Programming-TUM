
delete diary.txt
diary('diary.txt')
magicCUDA('solve_LSE_GPU')

N = 6890;
% N = 100;
A = randn(N,N); 
B = [1 1 3];



tic
[L, U, P] = lu(A);
toc

tic
[Q, R] = qr(A);
toc

tic
C = solve_LSE_GPU(A, B);
toc
L1 = tril(C,-1) + eye(size(A));
U1 = triu(C);

spy(abs(A-L1*U1) > 10e-5)