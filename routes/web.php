<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ForwardAuthController;
use App\Http\Controllers\LoginController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
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

    Route::get('profile', [ProfileController::class, 'view']);
    Route::post('profile/change-password', [ProfileController::class, 'changePassword']);

    Route::get('logout', [LoginController::class, 'logout']);
});

Route::middleware('guest')->group(function () {
    Route::view('password-reset', 'pages.password.forgot');
    Route::post('password-reset', [PasswordResetController::class, 'submitEmailForm']);
    Route::get('password-reset/{token}', [PasswordResetController::class, 'viewResetForm']);
    Route::post('password-reset/{token}', [PasswordResetController::class, 'submitResetForm']);
});

Route::get('_authum/forward-auth', [ForwardAuthController::class, 'handle'])->middleware(EnforceParentSessionLoggedInUser::class);

Route::get('dashboard/fake', [DashboardController::class, 'viewFake']);

Route::get('login', [LoginController::class, 'view'])->name('login');
Route::post('login', [LoginController::class, 'login'])->middleware('guest');
