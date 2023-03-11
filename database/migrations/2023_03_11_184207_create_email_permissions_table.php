<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up() {
        Schema::create('email_permissions', function (Blueprint $table) {
            $table->char('id', 42)->primary();
            $table->unsignedInteger('order')->index();
            $table->string('regex');
            $table->enum('if_matches', ['pass', 'fail']);
            $table->bigInteger('created_at');
            $table->bigInteger('updated_at');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down() {
        Schema::dropIfExists('email_permissions');
    }
};
