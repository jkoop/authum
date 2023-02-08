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
        Schema::create('domain_names', function (Blueprint $table) {
            $table->string('domain_name')->primary();
            $table->ulid('service_id')->index();
            $table->bigInteger('created_at');
            $table->bigInteger('updated_at');

            $table->foreign('service_id')->references('id')->on('services')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down() {
        Schema::dropIfExists('domain_names');
    }
};
