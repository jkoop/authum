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
        Schema::create('authentication_return_tokens', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('parent_session_id');
            $table->string('forward_to', 8191);
            $table->bigInteger('created_at');
            $table->bigInteger('updated_at');

            // commented out because the session may not be written yet
            // $table->foreign('parent_session_id')->references('id')->on('sessions')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down() {
        Schema::dropIfExists('authentication_return_tokens');
    }
};
