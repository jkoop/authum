<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ForwardAuthController;
use App\Http\Controllers\LoginController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\UserController;
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

Route::middleware(['auth', 'auth.enabled'])->group(function () {
    Route::get('/', [DashboardController::class, 'view']);

    Route::get('profile', [ProfileController::class, 'view']);
    Route::post('profile', [ProfileController::class, 'updateGeneral']);
    Route::post('profile/change-password', [ProfileController::class, 'changePassword']);
    Route::post('email-address', [ProfileController::class, 'sendVerifyEmailEmail'])->middleware('throttle');
    Route::get('add-email/{token}', [ProfileController::class, 'verifyEmail'])->middleware('throttle');
    Route::delete('email-address/{emailAddress}', [ProfileController::class, 'deleteEmail'])->middleware('can:delete,emailAddress');
});

Route::middleware('auth')->group(function () {
    Route::get('logout', [LoginController::class, 'logout']);
});

Route::middleware(['auth', 'auth.enabled', 'auth.admin'])->group(function () {
    Route::get('users', [UserController::class, 'list']);
    Route::get('user/{user}', [UserController::class, 'view']);
    Route::post('user/new', [UserController::class, 'create']);
    Route::post('user/{user}', [UserController::class, 'update']);
    Route::delete('user/{user}', [UserController::class, 'delete']);
    Route::post('user/{user}/change-password', [UserController::class, 'changePassword']);
    Route::post('user/{user}/email-address', [UserController::class, 'addEmailAddress']);

    Route::get('services', [ServiceController::class, 'list']);
    Route::get('service/{service}', [ServiceController::class, 'view']);
    Route::post('service/new', [ServiceController::class, 'create']);
    Route::post('service/{service}', [ServiceController::class, 'update']);
    Route::delete('service/{service}', [ServiceController::class, 'delete']);
    Route::post('service/{service}/domain-name', [ServiceController::class, 'addDomainName']);
    Route::delete('domain-name/{domainName}', [ServiceController::class, 'deleteDomainName']);
});

Route::middleware('guest')->group(function () {
    Route::view('password-reset', 'pages.password.forgot');
    Route::post('password-reset', [PasswordResetController::class, 'submitEmailForm'])->middleware('throttle');
    Route::get('password-reset/{token}', [PasswordResetController::class, 'viewResetForm']);
    Route::post('password-reset/{token}', [PasswordResetController::class, 'submitResetForm'])->middleware('throttle');
});

Route::get('_authum/forward-auth', [ForwardAuthController::class, 'handle'])->middleware(EnforceParentSessionLoggedInUser::class);

Route::get('dashboard/fake', [DashboardController::class, 'viewFake']);

Route::get('login', [LoginController::class, 'view'])->name('login');
Route::post('login', [LoginController::class, 'login'])->middleware(['guest', 'throttle']);
