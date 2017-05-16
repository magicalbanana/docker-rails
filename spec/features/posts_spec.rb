require 'rails_helper'

feature 'Post management' do
  before :each do
    30.times { create(:post) }
    Post.reindex
  end

  let!(:example_post) { create(:post, :reindex, title: 'Example', content: 'Lorem ipsum') }

  scenario 'User navigates through posts', js: true do
    visit posts_path

    expect(page).to have_selector('h1', text: 'Posts')
    expect(page).to have_xpath('.//table/tbody/tr', count: 25)
    expect(page).to have_selector('#post-count', text: '31 Posts')
    expect(page).to have_link('Add new Post', href: new_post_path)

    # Scroll down to load whole list via infinite scrolling
    page.execute_script "window.scrollBy(0, $(window).height())"
    expect(page).to have_xpath('.//table/tbody/tr', count: 31)

    # Scroll up again and go to single post by clicking on a row
    page.execute_script "window.scrollTo(0, 0)"
    find(:xpath, ".//table/tbody/tr[1]").click
    expect(page.current_path).to eq(post_path(example_post))

    # Go to homepage by clicking an the navbar logo
    find(:xpath, './/a[contains(@class, "navbar-brand")]').click
    expect(page.current_path).to eq(root_path)
  end

  scenario 'User searches for a post' do
    visit posts_path
    expect(page).to_not have_text('Posts matching')

    within '#search' do
      fill_in 'q', with: 'Exam'
    end
    click_on 'Search for Text'

    expect(page).to have_text('Posts matching')
    expect(page).to have_current_path(/q=Exam/)
    expect(page).to have_xpath('.//table/tbody/tr', count: 1, text: 'Example')
    expect(page).to have_selector('#post-count', text: '1 Post')
  end

  scenario 'User opens a single page', js: true do
    visit post_path(example_post)

    expect(page).to have_selector('h1', text: 'Example')
    expect(page).to have_selector('time', text: 'ago')
    expect(page).to have_link(href: edit_post_path(example_post), title: 'Edit Post')
    expect(page).to have_link(href: post_path(example_post, format: 'pdf'), title: 'Export Post as PDF')
  end

  scenario 'User opens a single page as PDF' do
    visit post_path(example_post, format: 'pdf')

    convert_pdf_to_page
    expect(page).to have_text('Example')
    expect(page).to have_text('Lorem ipsum')
  end

  scenario 'User edits an existing page' do
    visit edit_post_path(example_post)

    expect(page).to have_selector('h1', text: 'Editing Post')
    expect(page).to have_button('Update Post')

    fill_in 'post[title]', with: 'Bar'
    fill_in 'post[content]', with: 'dolor sit amet'
    click_on 'Update Post'

    expect(page.current_path).to eq(post_path(example_post))
    expect(page).to have_text 'Post was successfully updated.'
    expect(page).to have_selector('h1', text: 'Bar')
    expect(page).to have_selector('p', text: 'dolor sit amet')
  end

  scenario 'User sees auto-refreshed post (via ActionCable) if other user updates it', js: true do
    in_browser(:first_user) do
      visit post_path(example_post)

      expect(page).to have_selector('h1', text: 'Example')
      expect(page).to have_selector('p', text: 'Lorem ipsum')
    end

    in_browser(:second_user) do
      visit edit_post_path(example_post)

      fill_in 'post[title]', with: 'Fooo'
      fill_in 'post[content]', with: 'dolor sit amet'
      click_on 'Update Post'
    end

    in_browser(:first_user) do
      expect(page).to have_selector('h1', text: 'Fooo')
      expect(page).to have_selector('p', text: 'dolor sit amet')
    end
  end

  scenario 'User deletes an existing page', js: true do
    visit post_path(example_post)

    page.accept_alert 'Are you sure?' do
      find(:xpath, '//a[@title="Destroy"]').click
    end

    expect(page.current_path).to eq(posts_path)
    expect(page).to have_text 'Post was successfully destroyed.'
    expect(page).to_not have_selector('td', text: 'Example')
  end

  scenario 'User creates a new page', js: true do
    visit posts_path

    click_on 'Add new Post'

    expect(page.current_path).to eq(new_post_path)
    expect(page).to have_selector('h1', text: 'New Post')
    expect(page).to have_button('Create Post')

    fill_in 'post[title]', with: 'Bar'
    click_on 'Create Post'
    expect(page).to have_selector('div.form-group.has-error')
    fill_in 'post[content]', with: 'dolor sit amet'
    expect(page).to_not have_selector('div.form-group.has-error')
    click_on 'Create Post'

    expect(page).to have_text 'Post was successfully created.'
    expect(page).to have_selector('h1', text: 'Bar')
    expect(page).to have_selector('p', text: 'dolor sit amet')
  end
end