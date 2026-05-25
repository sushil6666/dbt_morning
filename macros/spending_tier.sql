{#
  spending_tier(amount_column)
  Classifies a ticket price into a visitor spending tier.
  Thresholds are calibrated to Horrorland ticket price ranges:
    premium  >= $200  (annual_pass full price)
    standard >= $100  (group/weekend pass range)
    budget   >= $40   (day pass standard range)
    discount  < $40   (heavily discounted tickets)
#}

{% macro spending_tier(amount_column) %}

    CASE
        WHEN {{ amount_column }} >= 200 THEN 'premium'
        WHEN {{ amount_column }} >= 100 THEN 'standard'
        WHEN {{ amount_column }} >= 40  THEN 'budget'
        ELSE 'discount'
    END

{% endmacro %}
