<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ForwardAuthController;
use App\Http\Controllers\LoginController;
use App\Http\Middleware\EnforceParentSessionLoggedInUser;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::middleware('auth')->group(function () {
    Route::get('/', [DashboardController::class, 'view']);
    Route::get('logout', [LoginController::class, 'logout']);
});

Route::get('_authum/forward-auth', [ForwardAuthController::class, 'handle'])->middleware(EnforceParentSessionLoggedInUser::class);

Route::get('/dashboard/fake', [DashboardController::class, 'viewFake']);

Route::get('login', [LoginController::class, 'view'])->name('login');
Route::post('login', [LoginController::class, 'login'])->middleware('guest');
