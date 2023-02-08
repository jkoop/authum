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
            $table->char('id', 42)->primary();
            $table->string('parent_session_id'); // don't add a foreign key constraint here
            $table->string('forward_to', 8191);
            $table->bigInteger('expires_at');
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
