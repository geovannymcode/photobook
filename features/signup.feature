Feature: Sign Up
In order to get sign up
A User
Should fill the sign up form

Scenario: Sign up
    Given I am on the "sign_up" page
    And I fill in "username" with "whitewolf"
    And I fill in "firstname" with "Jon"
    And I fill in "lastname" with "Snow"
    And I fill in "location" with "The wall"
    And I fill in "email" with "jon.snow@winterfell.co"
    And I fill in "password" with "123456"
    And I fill in "password_confirmation" with "123456"
    When I press "Sign up"
    Then page should have notice message "Welcome! You have signed up successfully."