<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Service>
 */
class ServiceFactory extends Factory {
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition() {
        $name = "";

        for ($i = rand(0, 7); $i < 10; $i++) {
            $name .= chr(rand(97, 122));
        }

        $name .= " ";

        for ($i = rand(2, 5); $i < 10; $i++) {
            $name .= chr(rand(97, 122));
        }

        return compact('name');
    }
}
